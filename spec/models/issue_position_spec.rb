require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WorkPackage do
  describe 'Story positions' do
    def build_work_package(options)
      FactoryGirl.build(:work_package, options.reverse_merge(:fixed_version_id => sprint_1.id,
                                                  :priority_id      => priority.id,
                                                  :project_id       => project.id,
                                                  :status_id        => status.id,
                                                  :tracker_id       => story_tracker.id))
    end

    def create_work_package(options)
      build_work_package(options).tap { |i| i.save! }
    end

    let(:status)   { FactoryGirl.create(:issue_status)    }
    let(:priority) { FactoryGirl.create(:priority_normal) }
    let(:project)  { FactoryGirl.create(:project)         }

    let(:story_tracker) { FactoryGirl.create(:tracker, :name => 'Story')    }
    let(:epic_tracker)  { FactoryGirl.create(:tracker, :name => 'Epic')     }
    let(:task_tracker)  { FactoryGirl.create(:tracker, :name => 'Task')     }
    let(:other_tracker) { FactoryGirl.create(:tracker, :name => 'Feedback') }

    let(:sprint_1) { FactoryGirl.create(:version, :project_id => project.id, :name => 'Sprint 1') }
    let(:sprint_2) { FactoryGirl.create(:version, :project_id => project.id, :name => 'Sprint 2') }

    let(:work_package_1) { create_work_package(:subject => 'WorkPackage 1', :fixed_version_id => sprint_1.id) }
    let(:work_package_2) { create_work_package(:subject => 'WorkPackage 2', :fixed_version_id => sprint_1.id) }
    let(:work_package_3) { create_work_package(:subject => 'WorkPackage 3', :fixed_version_id => sprint_1.id) }
    let(:work_package_4) { create_work_package(:subject => 'WorkPackage 4', :fixed_version_id => sprint_1.id) }
    let(:work_package_5) { create_work_package(:subject => 'WorkPackage 5', :fixed_version_id => sprint_1.id) }

    let(:work_package_a) { create_work_package(:subject => 'WorkPackage a', :fixed_version_id => sprint_2.id) }
    let(:work_package_b) { create_work_package(:subject => 'WorkPackage b', :fixed_version_id => sprint_2.id) }
    let(:work_package_c) { create_work_package(:subject => 'WorkPackage c', :fixed_version_id => sprint_2.id) }

    let(:feedback_1)  { create_work_package(:subject => 'Feedback 1', :fixed_version_id => sprint_1.id,
                                                               :tracker_id => other_tracker.id) }

    let(:task_1)  { create_work_package(:subject => 'Task 1', :fixed_version_id => sprint_1.id,
                                                       :tracker_id => task_tracker.id) }

    before do
      # had problems while writing these specs, that some elements kept creaping
      # around between tests. This should be fast enough to not harm anybody
      # while adding an additional safety net to make sure, that everything runs
      # in isolation.
      WorkPackage.delete_all
      IssuePriority.delete_all
      IssueStatus.delete_all
      Project.delete_all
      Tracker.delete_all
      Version.delete_all

      # enable and configure backlogs
      project.enabled_module_names = project.enabled_module_names + ["backlogs"]
      Setting.plugin_openproject_backlogs = {"story_trackers" => [story_tracker.id, epic_tracker.id],
                                 "task_tracker"   => task_tracker.id}

      # otherwise the tracker id's from the previous test are still active
      WorkPackage.instance_variable_set(:@backlogs_trackers, nil)

      project.trackers = [story_tracker, epic_tracker, task_tracker, other_tracker]
      sprint_1
      sprint_2

      # create and order work_packages
      work_package_1.move_to_bottom
      work_package_2.move_to_bottom
      work_package_3.move_to_bottom
      work_package_4.move_to_bottom
      work_package_5.move_to_bottom

      work_package_a.move_to_bottom
      work_package_b.move_to_bottom
      work_package_c.move_to_bottom
    end

    describe '- Creating an work_package in a sprint' do
      it 'adds it to the top of the list' do
        new_work_package = create_work_package(:subject => 'Newest WorkPackage', :fixed_version_id => sprint_1.id)

        new_work_package.should_not be_new_record
        new_work_package.should be_first
      end

      it 'reorders the existing work_packages' do
        new_work_package = create_work_package(:subject => 'Newest WorkPackage', :fixed_version_id => sprint_1.id)

        [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [2, 3, 4, 5, 6]
      end
    end

    describe '- Removing an work_package from the sprint' do
      it 'reorders the remaining work_packages' do
        work_package_2.fixed_version = sprint_2
        work_package_2.save!

        sprint_1.fixed_work_packages.all(:order => 'id').should == [work_package_1, work_package_3, work_package_4, work_package_5]
        sprint_1.fixed_work_packages.all(:order => 'id').each(&:reload).map(&:position).should == [1, 2, 3, 4]
      end
    end

    describe '- Adding an work_package to a sprint' do
      it 'adds it to the top of the list' do
        work_package_a.fixed_version = sprint_1
        work_package_a.save!

        work_package_a.should be_first
      end

      it 'reorders the existing work_packages' do
        work_package_a.fixed_version = sprint_1
        work_package_a.save!

        [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [2, 3, 4, 5, 6]
      end
    end

    describe '- Deleting an work_package in a sprint' do
      it 'reorders the existing work_packages' do
        work_package_3.destroy

        [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
      end
    end

    describe '- Changing the tracker' do
      describe 'by moving a story to another story tracker' do
        it 'keeps all positions in the sprint in tact' do
          work_package_3.tracker = epic_tracker
          work_package_3.save!

          [work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5]
        end
      end

      describe 'by moving a story to a non-backlogs tracker' do
        it 'removes it from any list' do
          work_package_3.tracker = other_tracker
          work_package_3.save!

          work_package_3.should_not be_in_list
        end

        it 'reorders the remaining stories' do
          work_package_3.tracker = other_tracker
          work_package_3.save!

          [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
        end
      end

      describe 'by moving a story to the task tracker' do
        it 'removes it from any list' do
          work_package_3.tracker = task_tracker
          work_package_3.save!

          work_package_3.should_not be_in_list
        end

        it 'reorders the remaining stories' do
          work_package_3.tracker = task_tracker
          work_package_3.save!

          [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
        end
      end

      describe 'by moving a task to the story tracker' do
        it 'adds it to the top of the list' do
          task_1.tracker = story_tracker
          task_1.save!

          task_1.should be_first
        end

        it 'reorders the existing stories' do
          task_1.tracker = story_tracker
          task_1.save!

          [task_1, work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5, 6]
        end
      end

      describe 'by moving a non-backlogs work_package to a story tracker' do
        it 'adds it to the top of the list' do
          feedback_1.tracker = story_tracker
          feedback_1.save!

          feedback_1.should be_first
        end

        it 'reorders the existing stories' do
          feedback_1.tracker = story_tracker
          feedback_1.save!

          [feedback_1, work_package_1, work_package_2, work_package_3, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4, 5, 6]
        end
      end
    end

    describe '- Moving work_packages between projects' do
      # N.B.: You cannot move a ticket to another project and change the
      # fixed_version at the same time. OTOH chiliproject tries to keep
      # the fixed_version if possible (e.g. within project hierarchies with
      # shared versions)

      let(:project_wo_backlogs) { FactoryGirl.create(:project) }
      let(:sub_project_wo_backlogs) { FactoryGirl.create(:project) }

      let(:shared_sprint)   { FactoryGirl.create(:version,
                                             :project_id => project.id,
                                             :name => 'Shared Sprint',
                                             :sharing => 'descendants') }

      let(:version_go_live) { FactoryGirl.create(:version,
                                             :project_id => project_wo_backlogs.id,
                                             :name => 'Go-Live') }

      before do
        project_wo_backlogs.enabled_module_names = project_wo_backlogs.enabled_module_names - ["backlogs"]
        sub_project_wo_backlogs.enabled_module_names = sub_project_wo_backlogs.enabled_module_names - ["backlogs"]

        project_wo_backlogs.trackers = [story_tracker, task_tracker, other_tracker]
        sub_project_wo_backlogs.trackers = [story_tracker, task_tracker, other_tracker]

        sub_project_wo_backlogs.move_to_child_of(project)

        shared_sprint
        version_go_live
      end

      describe '- Moving an work_package from a project without backlogs to a backlogs_enabled project' do
        describe 'if the fixed_version may not be kept' do
          let(:work_package_i) { create_work_package(:subject => 'WorkPackage I',
                                       :fixed_version_id => version_go_live.id,
                                       :project_id => project_wo_backlogs.id) }
          before do
            work_package_i
          end

          it 'sets the fixed_version_id to nil' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.fixed_version.should be_nil
          end

          it 'removes it from any list' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.should_not be_in_list
          end
        end

        describe 'if the fixed_version may be kept' do
          let(:work_package_i) { create_work_package(:subject => 'WorkPackage I',
                                       :fixed_version_id => shared_sprint.id,
                                       :project_id => sub_project_wo_backlogs.id) }

          before do
            work_package_i
          end

          it 'keeps the fixed_version_id' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.fixed_version.should == shared_sprint
          end

          it 'adds it to the top of the list' do
            result = work_package_i.move_to_project(project)

            result.should be_true

            work_package_i.should be_first
          end
        end
      end

      describe '- Moving an work_package away from backlogs_enabled project to a project without backlogs' do
        describe 'if the fixed_version may not be kept' do
          it 'sets the fixed_version_id to nil' do
            result = work_package_3.move_to_project(project_wo_backlogs)

            result.should be_true

            work_package_3.fixed_version.should be_nil
          end

          it 'removes it from any list' do
            result = work_package_3.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_3.should_not be_in_list
          end

          it 'reorders the remaining work_packages' do
            result = work_package_3.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            [work_package_1, work_package_2, work_package_4, work_package_5].each(&:reload).map(&:position).should == [1, 2, 3, 4]
          end
        end

        describe 'if the fixed_version may be kept' do
          let(:work_package_i)   { create_work_package(:subject => 'WorkPackage I',
                                         :fixed_version_id => shared_sprint.id) }
          let(:work_package_ii)  { create_work_package(:subject => 'WorkPackage II',
                                         :fixed_version_id => shared_sprint.id) }
          let(:work_package_iii) { create_work_package(:subject => 'WorkPackage III',
                                         :fixed_version_id => shared_sprint.id) }

          before do
            work_package_i.move_to_bottom
            work_package_ii.move_to_bottom
            work_package_iii.move_to_bottom

            [work_package_i, work_package_ii, work_package_iii].map(&:position).should == [1, 2, 3]
          end

          it 'keeps the fixed_version_id' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_ii.fixed_version.should == shared_sprint
          end

          it 'removes it from any list' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            work_package_ii.should_not be_in_list
          end

          it 'reorders the remaining work_packages' do
            result = work_package_ii.move_to_project(sub_project_wo_backlogs)

            result.should be_true

            [work_package_i, work_package_iii].each(&:reload).map(&:position).should == [1, 2]
          end
        end
      end
    end
  end
end
